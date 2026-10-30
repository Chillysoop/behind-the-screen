-- Set the stage: the map half of the fight builder (B9 rebuilt on the SRD). The place's board on
-- the 20 x 13 grid, its own scenery shown dark; pick a set piece (a table is Half Cover, a pillar
-- Three-Quarters, a wall Total Cover, a door opens, ice is slippery, a torch lights the dark) and
-- click to set it down. Click your own piece again to turn it, or to work a door (shut, open,
-- locked). Clear takes a piece off, or the place's own scenery. The map is saved with the place
-- (game/model/maps.lua) and the table sets it out as the place from then on.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local util = require "game.model.util"
local maps = require "game.model.maps"
local board = require "game.model.board"
local props = require "game.data.props"
local matchup = require "game.model.matchup"

local M = {}

M.CELL = 38
local GROUP_COLOR = {
    Furniture = kit.rgba("#9a7442"), ["Walls and doors"] = kit.rgba("#8a8178"), Cover = kit.rgba("#b08a5a"),
    Ground = kit.rgba("#5c7a42"), Light = kit.rgba("#e0a640"), ["Traps, starts"] = kit.rgba("#8a52a0"),
}
local ICE = kit.rgba("#9cc6d8")
local TRAP = kit.rgba("#8a52a0")
local TEMPLATE_NAME = { camp = "Camp", forest = "Woods", road = "Road", ruins = "Ruins", underground = "Underground",
                        tavern = "Tavern", town = "Street", market_generic = "Market", bridge = "Bridge", dock = "Waterside",
                        blank = "Open ground" }
local FACING = { [0] = "facing south", "facing west", "facing north", "facing east" }

local function group_of(kind)
    for _, grp in ipairs(maps.PALETTE) do
        for _, it in ipairs(grp.items) do
            if it.kind == kind or (it.id == "wall" and (kind == "stone_wall" or kind == "wall_room")) then
                return grp.group
            end
        end
    end
    if kind == "door_open" or kind == "door_locked" then
        return "Walls and doors"
    end
    return "Furniture"
end

-- The boards on offer for a place: its own first (when it has one), then the general ones.
local function templates_for(auto)
    local list = {}
    if auto and not TEMPLATE_NAME[auto] then
        table.insert(list, auto)
    end
    for _, t in ipairs(maps.TEMPLATES) do
        table.insert(list, t)
    end
    return list
end

-- The scene's place, and its map (nil until the first piece goes down). (v2: aimed at one of the
-- DM's own maps from the map repository, the "place" is that map: game/model/map_repo.lua keeps
-- its pieces at campaign.maps["mine:<id>"].)
local function place_of(app)
    local t = app.map_target
    if t and t.mine then
        local meta = app.campaign.my_maps and app.campaign.my_maps[t.mine]
        local name = meta and meta.name or "your map"
        return { id = "mine:" .. t.mine, name = name, short = name }, { type = "exploration", slots = {}, own = true }
    end
    local s = app.campaign.prep.scenes[app.enc_scene]
    return s and s.slots.location, s
end

function M.map_of(app)
    local loc = place_of(app)
    return loc and maps.get(app.campaign, loc.id) or nil
end

local function redraw(app)
    if app.refresh then
        app.refresh()
    end
end

-- Lay the chosen piece on square (x, y), making the map if this is the first one.
function M.paint(app, x, y)
    local loc, s = place_of(app)
    if not loc then
        return false
    end
    local m = maps.get(app.campaign, loc.id)
    local tool = app.map_piece or "table_round"
    if not m then
        if tool == "erase" then
            return false
        end
        m = maps.new(app.campaign, loc.id, maps.auto_template(app.campaign, loc, s.type))
    end
    local changed, why = maps.place(m, tool, x, y, app.map_rot or 0)
    app.map_why = (not changed) and why or nil
    if changed then
        app.prep_dirty = true
    end
    return changed
end

-- How lit each square is on a dark map (for the preview): 0 bright, 1 dim, 2 dark.
local function light_grid(c, W, H)
    local out = {}
    for x = 1, W do
        for y = 1, H do
            local best = 2
            for _, l in ipairs(c.lights) do
                local d = 5 * math.max(math.abs(x - l.x), math.abs(y - l.y))
                if d <= l.bright then
                    best = 0
                elseif d <= l.bright + l.dim then
                    best = math.min(best, 1)
                end
            end
            out[x * 1000 + y] = best
        end
    end
    return out
end

-- Draw the map tab's body inside the builder at (x, y), w wide.
function M.draw(app, x, y, w, h, ids, hazard)
    local loc, s = place_of(app)
    local W, H = content.terrain_layout.W, content.terrain_layout.H
    local C = M.CELL
    local gx, gy = x, y + 26
    if not loc then
        kit.text(x, y, "SET THE STAGE", "ui14", theme.gold)
        kit.text(x, y + 30, "Put a place on this stop first. A map is saved with its place, so going back there uses it.",
            "ui18", theme.faint, { w = W * C })
        return
    end
    local m = maps.get(app.campaign, loc.id)
    local template = m and m.template or maps.auto_template(app.campaign, loc, s.type)
    local id = m and maps.board_id(m) or template
    local c = board.compile(id)
    kit.text(x, y, "SET THE STAGE: " .. string.upper(loc.short or loc.name), "ui14", theme.gold)
    kit.text(x + W * C, y, m and ("Saved with the place. " .. util.int(maps.count(m)) .. " of " .. util.int(maps.MAX_PIECES)
        .. " pieces.") or "Nothing set yet: the place as it is.", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    kit.box(gx - 4, gy - 4, W * C + 8, H * C + 8, kit.rgba("#3d4a32"), { radius = 6 })
    for i = 0, W do
        kit.box(gx + i * C, gy, 1, H * C, kit.rgba("#000000", 0.18), { round = false })
    end
    for j = 0, H do
        kit.box(gx, gy + j * C, W * C, 1, kit.rgba("#000000", 0.18), { round = false })
    end
    local function cell(cx, cy, inset, color, radius)
        kit.box(gx + (cx - 1) * C + inset, gy + (cy - 1) * C + inset, C - 2 * inset, C - 2 * inset, color, { radius = radius or 4 })
    end
    -- Rough ground and ice under everything.
    for k in pairs(c.rough) do
        local rx, ry = maps.split(k)
        cell(rx, ry, 6, c.slippery[k] and ICE or kit.rgba("#5d7a3e", 0.55))
    end
    -- What blocks: the place's own scenery dark (brown for cover), the DM's pieces in colour.
    local mine = {}
    for _, p in ipairs(m and m.props or {}) do
        for _, sq in ipairs(board.squares(p.kind, p.x, p.y, p.r)) do
            mine[maps.key(sq[1], sq[2])] = p
        end
    end
    for _, sq in ipairs(c.blocked) do
        local k = maps.key(sq[1], sq[2])
        if not mine[k] then
            local covers = c.cover[k]
            cell(sq[1], sq[2], 2, covers and kit.rgba("#4a3626", 0.85) or kit.rgba("#1b1714", 0.75))
        end
    end
    for k, p in pairs(mine) do
        local px, py = maps.split(k)
        local kd = props[p.kind] or {}
        local col = p.kind == "ice" and ICE or GROUP_COLOR[group_of(p.kind)] or theme.dim
        cell(px, py, kd.blocks and 3 or 8, col, 5)
        if kd.door then
            kit.text(gx + (px - 0.5) * C, gy + (py - 0.5) * C, ({ closed = "D", open = "O", locked = "L" })[kd.door], "ui18b",
                theme.ink, { pivot = gui.PIVOT_CENTER })
        elseif kd.deg == "three_quarters" then
            kit.text(gx + (px - 0.5) * C, gy + (py - 0.5) * C, "3/4", "ui14", theme.ink, { pivot = gui.PIVOT_CENTER })
        elseif kd.opaque then
            kit.box(gx + (px - 1) * C + 8, gy + (py - 0.5) * C - 1, C - 16, 3, theme.ink, { round = false })
        end
    end
    for k in pairs(m and m.traps or {}) do
        local tx, ty = maps.split(k)
        cell(tx, ty, 9, TRAP, 3)
    end
    -- The dark, and what the map's fires and lamps light.
    if m and m.light == "dark" then
        local lg = light_grid(c, W, H)
        for cx = 1, W do
            for cy = 1, H do
                local v = lg[cx * 1000 + cy]
                if v > 0 then
                    kit.box(gx + (cx - 1) * C, gy + (cy - 1) * C, C, C, kit.rgba("#05070d", v == 2 and 0.55 or 0.28), { round = false })
                end
            end
        end
    elseif m and m.light == "dim" then
        kit.box(gx, gy, W * C, H * C, kit.rgba("#05070d", 0.22), { round = false })
    end
    local party = (m and m.party) or c.party
    local foes = (m and m.foes) or c.foes
    kit.dot(gx + (party[1] - 0.5) * C, gy + (party[2] - 0.5) * C, C - 8, theme.gold)
    kit.text(gx + (party[1] - 0.5) * C, gy + (party[2] - 0.5) * C, "P", "ui18b", theme.ink, { pivot = gui.PIVOT_CENTER })
    kit.dot(gx + (foes[1] - 0.5) * C, gy + (foes[2] - 0.5) * C, C - 8, theme.red)
    kit.text(gx + (foes[1] - 0.5) * C, gy + (foes[2] - 0.5) * C, "M", "ui18b", theme.ink, { pivot = gui.PIVOT_CENTER })
    -- One button over the grid: where the click lands says which square.
    kit.button(gx, gy, W * C, H * C, "", function()
        local cl = kit.click
        if not cl then
            return
        end
        local cx = math.floor((cl.x - gx) / C) + 1
        local cy = math.floor((cl.y - gy) / C) + 1
        M.paint(app, cx, cy)
        redraw(app)
    end, { color = kit.rgba("#000000", 0), hover = kit.rgba("#ffffff", 0.04), key = "map_grid" })
    -- Under the grid: the piece in hand and what it does.
    local ly = gy + H * C + 12
    local tool = app.map_piece or "table_round"
    local item = maps.ITEM[tool] or { name = tool }
    local kind = tool == "wall" and maps.wall_kind(template) or tool
    local rules = props[kind] and maps.rules_text(kind) or ({
        trap = "A hidden trap: whoever steps on it springs it.", party = "Where the heroes come in.",
        foes = "Where the monsters wait.", erase = "Takes off your piece, a trap or a start, or the place's own scenery under it.",
    })[tool] or ""
    kit.text(x, ly, string.upper(item.name), "ui14", theme.gold)
    kit.text(x + 140, ly, rules, "ui14", theme.text, { w = W * C - 300 })
    if props[kind] then
        local fw, fh = board.size(kind, app.map_rot or 0)
        kit.button(x + W * C - 150, ly - 4, 150, 26, "Turn (" .. FACING[app.map_rot or 0] .. ")", function()
            app.map_rot = ((app.map_rot or 0) + 1) % 4
            redraw(app)
        end, { font = "ui14", key = "map_turn", enabled = fw ~= fh or props[kind].door ~= nil or kind == "stone_wall" or kind == "wall_room" })
    end
    local hint = app.map_why or "Click a square to set it down. Click your piece again to turn it; a door goes shut, open, locked."
    kit.text(x, ly + 26, hint, "ui14", app.map_why and theme.orange or theme.faint, { w = W * C })
    if m and m.changed then
        local ledger = require "game.model.ledger"
        local st = ledger.place_state(app.campaign, loc.id)
        kit.text(x, ly + 48, "The world changed this place since you set it" .. (st and (": " .. string.lower(st.label)) or "")
            .. ". Check the map still fits.", "ui14", theme.orange, { w = W * C - 200 })
    end
    M.key(x, ly + 84, W * C)
    if m then
        kit.button(x + W * C - 150, ly + 44, 150, 28, "Clear the map", function()
            maps.remove(app.campaign, loc.id)
            app.prep_dirty = true
            redraw(app)
        end, { font = "ui14", key = "map_clear" })
    end
end

-- The right-hand column: the board, the light, the pieces, the trap, and how hard it is now.
function M.side(app, x, y, w, ids, hazard)
    local loc, s = place_of(app)
    local m = loc and maps.get(app.campaign, loc.id)
    local auto = loc and ((s.own and m and m.template) or maps.auto_template(app.campaign, loc, s.type))
    local function get_map(t)
        return maps.get(app.campaign, loc.id) or maps.new(app.campaign, loc.id, t or auto)
    end
    kit.text(x, y, "THE PLACE", "ui14", theme.gold)
    local ty = y + 20
    local bw = (w - 18) / 4
    local list = templates_for(auto)
    for k, t in ipairs(list) do
        local col, row = (k - 1) % 4, math.floor((k - 1) / 4)
        local on = (m and m.template or auto) == t
        kit.button(x + col * (bw + 6), ty + row * 30, bw, 26, (TEMPLATE_NAME[t] or "This place") .. (t == auto and " *" or ""), function()
            if not loc then
                return
            end
            maps.set_template(get_map(t), t)
            app.prep_dirty = true
            redraw(app)
        end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, enabled = loc ~= nil,
               key = "map_template_" .. t })
    end
    ty = ty + math.ceil(#list / 4) * 30 + 8
    -- The light (SRD 5.2.1 "Light").
    kit.text(x, ty, "LIGHT", "ui14", theme.gold)
    local lw = (w - 18) / 4
    for k, l in ipairs(maps.LIGHTS) do
        local on = (m and m.light) == l.id
        kit.button(x + (k - 1) * (lw + 6), ty + 20, lw, 26, l.name, function()
            if not loc then
                return
            end
            get_map().light = l.id
            app.prep_dirty = true
            redraw(app)
        end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, enabled = loc ~= nil,
               key = "map_light_" .. (l.id or "place") })
    end
    local lt = m and m.light and maps.LIGHTS[({ bright = 2, dim = 3, dark = 4 })[m.light]]
    ty = ty + 52
    if lt then
        kit.text(x, ty, lt.about, "ui14", theme.dim, { w = w, lines = 1 })
        ty = ty + 20
    end
    -- The set pieces, by what they're for.
    local sel = app.map_piece or "table_round"
    local iw = (w - 110 - 18) / 4
    for _, grp in ipairs(maps.PALETTE) do
        kit.text(x, ty + 5, grp.group, "ui14", theme.dim, { w = 104, lines = 2 })
        for k, it in ipairs(grp.items) do
            local col, row = (k - 1) % 4, math.floor((k - 1) / 4)
            local key = it.id or it.kind
            local bx, by = x + 110 + col * (iw + 6), ty + row * 30
            kit.button(bx, by, iw, 26, "", function()
                app.map_piece = key
                app.map_why = nil
                redraw(app)
            end, { color = sel == key and theme.go or theme.panel2, hover = theme.button_hover, enabled = loc ~= nil,
                   key = "map_piece_" .. key })
            kit.box(bx + 5, by + 7, 12, 12, (key == "ice" and ICE) or (key == "party" and theme.gold) or (key == "foes" and theme.red)
                or (key == "erase" and theme.faint) or GROUP_COLOR[grp.group], { radius = 3 })
            kit.text(bx + 22, by + 4, it.name, "ui14", theme.text, { w = iw - 26, lines = 1 })
        end
        ty = ty + math.ceil(#grp.items / 4) * 30 + 4
    end
    ty = ty + 4
    -- Which SRD trap the trap squares are.
    local hz = require "game.rules.data.hazards"
    local trap = (m and m.trap) or maps.TRAP
    local td = hz.traps[trap]
    kit.text(x, ty, "TRAP", "ui14", theme.gold)
    kit.text(x + 52, ty, td.name .. " (" .. td.src .. ")", "ui14", theme.text, { w = w - 140, lines = 1 })
    kit.button(x + w - 80, ty - 4, 80, 26, "Change", function()
        if not loc then
            return
        end
        local mm = get_map()
        local order = hz.trap_order
        local at = 1
        for k, tid in ipairs(order) do
            if tid == trap then
                at = k
            end
        end
        mm.trap = order[at % #order + 1]
        app.prep_dirty = true
        redraw(app)
    end, { font = "ui14", enabled = loc ~= nil, key = "map_trap" })
    ty = ty + 30
    if s and s.own then
        -- (One of the DM's own maps: no fight to weigh yet. The repository sets it for a room.)
        kit.text(x, ty, "Saved in your maps. Back in the map repository, set it for a room or open it as a side room.",
            "ui14", theme.faint, { w = w })
        return
    end
    -- How hard, with the map.
    local tilt, why = maps.tilt(m)
    local a = matchup.analyze(app.campaign, ids, hazard, tilt)
    kit.text(x, ty, "HOW HARD, WITH THE MAP", "ui14", theme.gold)
    ty = ty + 22
    if a.meter then
        local b = a.budget
        local scale = math.max(b.high * 1.5, a.xp)
        kit.box(x, ty, w, 12, kit.rgba("#000000", 0.35), { radius = 6 })
        kit.box(x, ty, math.max(2, w * math.min(1, a.xp / scale)), 12,
            a.xp > b.high and theme.red or (a.xp > b.moderate and theme.orange or (a.xp > b.low and theme.gold or theme.teal)),
            { radius = 6 })
        for _, mark in ipairs({ { b.low, "Low" }, { b.moderate, "Moderate" }, { b.high, "High" } }) do
            local mx = x + w * mark[1] / scale
            kit.box(mx - 1, ty - 4, 2, 20, theme.text, { round = false })
            kit.text(mx, ty + 16, mark[2], "ui14", theme.dim, { pivot = gui.PIVOT_N })
        end
        ty = ty + 38
        local line = (a.meter.danger and (a.meter.danger .. ". ") or "") .. (tilt ~= 0 and ("The map makes it "
            .. (tilt > 0 and "harder" or "easier") .. " (" .. util.join_names(why) .. ").") or "The map doesn't tilt it either way yet.")
        kit.text(x, ty, line, "ui14", theme.text, { w = w, lines = 2 })
    else
        kit.text(x, ty, "No monsters yet: add them on The fight tab.", "ui14", theme.faint)
    end
end

-- What the marks on the map are (the newcomer playtest, October 16: "P and M, no legend"), under
-- the grid: x, y its top left, w the grid's width.
function M.key(x, y, w)
    kit.text(x, y, "ON THE MAP", "ui14", theme.gold)
    local key = {
        { "P", theme.gold, "The heroes start here" },
        { "M", theme.red, "The monsters start here" },
        { "", TRAP, "A trap, hidden till stepped on" },
        { "", kit.rgba("#4a3626", 0.85), "Cover: +2 to AC, +5 at 3/4" },
        { "", kit.rgba("#1b1714", 0.75), "Blocks the way and the view" },
    }
    local kw = (w - 24) / 3
    for k, row in ipairs(key) do
        local col, r = (k - 1) % 3, math.floor((k - 1) / 3)
        local kx, ky = x + col * (kw + 12), y + 22 + r * 26
        if row[1] ~= "" then
            kit.dot(kx + 9, ky + 9, 18, row[2])
            kit.text(kx + 9, ky + 9, row[1], "ui14", theme.ink, { pivot = gui.PIVOT_CENTER })
        else
            kit.box(kx - 1, ky - 1, 20, 20, kit.rgba("#ffffff", 0.25), { radius = 5 })
            kit.box(kx, ky, 18, 18, row[2], { radius = 4 })
        end
        kit.text(kx + 26, ky, row[3], "ui14", theme.dim, { w = kw - 28, lines = 1 })
    end
end

return M
