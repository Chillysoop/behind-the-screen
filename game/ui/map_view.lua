-- Quick maps (M8, B9): the map half of the fight builder. The place's terrain template on the
-- 20 x 13 grid, the set's own scenery shown dark; pick a piece and click squares to lay it
-- (click it again to take it off). The difficulty meter moves as the map changes. The map is
-- saved with the place (game/model/maps.lua) and stands in for the automatic staging there.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local util = require "game.model.util"
local maps = require "game.model.maps"
local matchup = require "game.model.matchup"

local M = {}

M.CELL = 38
local PIECE_COLOR = {
    wall = kit.rgba("#8a8178"), cover = kit.rgba("#9a7442"), rough = kit.rgba("#5c7a42"), trap = kit.rgba("#8a52a0"),
}
local TEMPLATE_NAME = { camp = "Camp", forest = "Woods", road = "Road", ruins = "Ruins", underground = "Underground",
                        tavern = "Tavern", town = "Street", market_generic = "Market", bridge = "Bridge", dock = "Waterside",
                        blank = "Open ground" }

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

-- The scene's place, and its map (nil until the first piece goes down).
local function place_of(app)
    local s = app.campaign.prep.scenes[app.enc_scene]
    return s and s.slots.location, s
end

function M.map_of(app)
    local loc = place_of(app)
    return loc and maps.get(app.campaign, loc.id) or nil
end

-- Lay the chosen piece on square (x, y), making the map if this is the first one.
function M.paint(app, x, y)
    local loc, s = place_of(app)
    if not loc then
        return false
    end
    local m = maps.get(app.campaign, loc.id)
    if not m then
        if (app.map_piece or "wall") == "erase" then
            return false
        end
        m = maps.new(app.campaign, loc.id, maps.auto_template(app.campaign, loc, s.type))
    end
    local changed = maps.place(m, app.map_piece or "wall", x, y)
    if changed then
        app.prep_dirty = true
    end
    return changed
end

local function redraw(app)
    if app.refresh then
        app.refresh()
    end
end

-- Draw the map tab's body inside the builder at (x, y), w wide.
function M.draw(app, x, y, w, h, ids, hazard)
    local loc, s = place_of(app)
    local W, H = content.terrain_layout.W, content.terrain_layout.H
    local C = M.CELL
    local gx, gy = x, y + 26
    if not loc then
        kit.text(x, y, "THE MAP", "ui14", theme.gold)
        kit.text(x, y + 30, "Put a place on this scene first. A map is saved with its place, so going back there uses it.",
            "ui18", theme.faint, { w = W * C })
        return
    end
    local m = maps.get(app.campaign, loc.id)
    local template = m and m.template or maps.auto_template(app.campaign, loc, s.type)
    local set = content.terrain_layout.sets[template] or content.terrain_layout.sets.blank
    kit.text(x, y, "THE MAP: " .. string.upper(loc.short or loc.name), "ui14", theme.gold)
    kit.text(x + W * C, y, m and ("Saved with the place. " .. util.int(maps.count(m)) .. " of " .. util.int(maps.MAX_PIECES)
        .. " pieces.") or "Nothing drawn yet: the table stages it as usual.", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    -- The mat, the set's own scenery, the pieces and where everyone starts.
    kit.box(gx - 4, gy - 4, W * C + 8, H * C + 8, kit.rgba("#3d4a32"), { radius = 6 })
    for i = 0, W do
        kit.box(gx + i * C, gy, 1, H * C, kit.rgba("#000000", 0.18), { round = false })
    end
    for j = 0, H do
        kit.box(gx, gy + j * C, W * C, 1, kit.rgba("#000000", 0.18), { round = false })
    end
    for _, sq in ipairs(set.blocked) do
        kit.box(gx + (sq[1] - 1) * C + 2, gy + (sq[2] - 1) * C + 2, C - 4, C - 4, kit.rgba("#1b1714", 0.75), { radius = 4 })
    end
    for k, kind in pairs(m and m.pieces or {}) do
        local px, py = maps.split(k)
        kit.box(gx + (px - 1) * C + 3, gy + (py - 1) * C + 3, C - 6, C - 6, PIECE_COLOR[kind] or theme.dim, { radius = 5 })
    end
    local party = m and m.party or set.party
    local foes = m and m.foes or set.foes
    kit.dot(gx + (party[1] - 0.5) * C, gy + (party[2] - 0.5) * C, C - 8, theme.gold)
    kit.text(gx + (party[1] - 0.5) * C, gy + (party[2] - 0.5) * C, "P", "ui18b", theme.ink, { pivot = gui.PIVOT_CENTER })
    kit.dot(gx + (foes[1] - 0.5) * C, gy + (foes[2] - 0.5) * C, C - 8, theme.red)
    kit.text(gx + (foes[1] - 0.5) * C, gy + (foes[2] - 0.5) * C, "M", "ui18b", theme.ink, { pivot = gui.PIVOT_CENTER })
    -- One button over the whole grid: where the click lands says which square.
    kit.button(gx, gy, W * C, H * C, "", function()
        local cl = kit.click
        if not cl then
            return
        end
        local cx = math.floor((cl.x - gx) / C) + 1
        local cy = math.floor((cl.y - gy) / C) + 1
        if M.paint(app, cx, cy) then
            redraw(app)
        end
    end, { color = kit.rgba("#000000", 0), hover = kit.rgba("#ffffff", 0.04), key = "map_grid" })
    local ly = gy + H * C + 10
    kit.text(x, ly, "Dark squares are the " .. string.lower(set.title) .. "'s own scenery. P: the party comes in here. M: the monsters wait here.",
        "ui14", theme.faint, { w = W * C })
    if m and m.changed then
        local ledger = require "game.model.ledger"
        local st = ledger.place_state(app.campaign, loc.id)
        kit.text(x, ly + 22, "The world changed this place since you drew it" .. (st and (": " .. string.lower(st.label)) or "")
            .. ". Check the map still fits.", "ui14", theme.orange, { w = W * C })
    end
end

-- The right-hand column on the map tab: template, pieces, the trap, and how hard it is now.
function M.side(app, x, y, w, ids, hazard)
    local loc, s = place_of(app)
    local m = loc and maps.get(app.campaign, loc.id)
    local auto = loc and maps.auto_template(app.campaign, loc, s.type)
    kit.text(x, y, "TEMPLATE", "ui14", theme.gold)
    local ty = y + 22
    local bw = (w - 12) / 3
    local list = templates_for(auto)
    for k, t in ipairs(list) do
        local col, row = (k - 1) % 3, math.floor((k - 1) / 3)
        local on = (m and m.template or auto) == t
        local name = TEMPLATE_NAME[t] or "This place"
        kit.button(x + col * (bw + 6), ty + row * 30, bw, 26, name .. (t == auto and " *" or ""), function()
            if not loc then
                return
            end
            local mm = maps.get(app.campaign, loc.id) or maps.new(app.campaign, loc.id, t)
            maps.set_template(mm, t)
            app.prep_dirty = true
            redraw(app)
        end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, enabled = loc ~= nil,
               key = "map_template_" .. t })
    end
    ty = ty + math.ceil(#list / 3) * 30 + 2
    kit.text(x, ty, "* the place's own. Changing it changes the scenery on the table.", "ui14", theme.faint, { w = w })
    ty = ty + 30
    kit.text(x, ty, "PIECES", "ui14", theme.gold)
    ty = ty + 22
    local sel = app.map_piece or "wall"
    for k, p in ipairs(maps.PIECES) do
        local col, row = (k - 1) % 2, math.floor((k - 1) / 2)
        local pw = (w - 6) / 2
        local px, py = x + col * (pw + 6), ty + row * 50
        kit.button(px, py, pw, 44, "", function()
            app.map_piece = p.id
            redraw(app)
        end, { color = sel == p.id and theme.go or theme.panel2, hover = theme.button_hover, enabled = loc ~= nil,
               key = "map_piece_" .. p.id })
        local sw = PIECE_COLOR[p.id] or (p.id == "party" and theme.gold) or (p.id == "foes" and theme.red) or theme.faint
        kit.box(px + 8, py + 10, 24, 24, sw, { radius = 4 })
        kit.text(px + 40, py + 4, p.name, "ui14", theme.text)
        kit.text(px + 40, py + 22, p.about, "ui14", theme.dim, { w = pw - 46, lines = 1 })
    end
    ty = ty + 4 * 50 + 4
    -- Which SRD trap the trap squares are.
    local hz = require "game.rules.data.hazards"
    local trap = (m and m.trap) or maps.TRAP
    local td = hz.traps[trap]
    kit.text(x, ty, "TRAP", "ui14", theme.gold)
    kit.text(x + 52, ty, td.name .. " (" .. td.src .. ")", "ui14", theme.text, { w = w - 140 })
    kit.button(x + w - 80, ty - 4, 80, 26, "Change", function()
        if not loc then
            return
        end
        local mm = maps.get(app.campaign, loc.id) or maps.new(app.campaign, loc.id, auto)
        local order = hz.trap_order
        local at = 1
        for k, id in ipairs(order) do
            if id == trap then
                at = k
            end
        end
        mm.trap = order[at % #order + 1]
        app.prep_dirty = true
        redraw(app)
    end, { font = "ui14", enabled = loc ~= nil, key = "map_trap" })
    ty = ty + 24
    kit.text(x, ty, td.about, "ui14", theme.dim, { w = w, lines = 2 })
    ty = ty + 44
    -- How hard, with the map.
    local tilt, why = maps.tilt(m)
    local a = matchup.analyze(app.campaign, ids, hazard, tilt)
    kit.text(x, ty, "HOW HARD, WITH THE MAP", "ui14", theme.gold)
    ty = ty + 24
    if a.meter then
        local b = a.budget
        local scale = math.max(b.high * 1.5, a.xp)
        kit.box(x, ty, w, 14, kit.rgba("#000000", 0.35), { radius = 6 })
        kit.box(x, ty, math.max(2, w * math.min(1, a.xp / scale)), 14,
            a.xp > b.high and theme.red or (a.xp > b.moderate and theme.orange or (a.xp > b.low and theme.gold or theme.teal)),
            { radius = 6 })
        for _, mark in ipairs({ { b.low, "Low" }, { b.moderate, "Moderate" }, { b.high, "High" } }) do
            local mx = x + w * mark[1] / scale
            kit.box(mx - 1, ty - 4, 2, 22, theme.text, { round = false })
            kit.text(mx, ty + 20, mark[2], "ui14", theme.dim, { pivot = gui.PIVOT_N })
        end
        ty = ty + 44
        local line = (a.meter.danger and (a.meter.danger .. ". ") or "") .. (tilt ~= 0 and ("The map makes it "
            .. (tilt > 0 and "harder" or "easier") .. " (" .. util.join_names(why) .. ").") or "The map doesn't tilt it either way yet.")
        kit.text(x, ty, line, "ui14", theme.text, { w = w })
        ty = ty + kit.text_height(line, "ui14", w) + 8
    else
        kit.text(x, ty, "No monsters yet: add them on The fight tab.", "ui14", theme.faint)
        ty = ty + 24
    end
    if m then
        kit.button(x, ty + 4, 200, 30, "Clear the map", function()
            maps.remove(app.campaign, loc.id)
            app.prep_dirty = true
            redraw(app)
        end, { font = "ui14", key = "map_clear" })
    end
end

return M
