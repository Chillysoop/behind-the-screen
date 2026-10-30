-- The map repository (v2, October 30): every map the DM can put on the table (game/model/map_repo.lua).
-- Pick a group, pick a map, see it square by square with its places of interest; then, in prep,
-- set it for one of the adventure's rooms or open a side room off one, and on game night set it
-- for the next scene. Any map opens in the map maker (built-in ones as your own copy); "New map"
-- starts one from scratch.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local adventure = require "game.model.adventure"
local map_repo = require "game.model.map_repo"

local M = {}

local X, Y, W, H = 70, 36, 1460, 828
local CELL = 38
local COLOURS = {
    wall = kit.rgba("#5a524a"), door = kit.rgba("#8a5a30"), water = kit.rgba("#3a6f86"), plants = kit.rgba("#4f7a3a"),
    cover = kit.rgba("#9a7442"), ground = kit.rgba("#4a4038"), rough = kit.rgba("#6a5a44"),
}

function M.open(app, ref)
    app.overlay = "maps"
    app.mr_sel = ref or app.mr_sel
    app.mr_pick = nil
    M.draw(app)
end

function M.close(app)
    if app.mr_layer then
        kit.drop(app.mr_layer)
        app.mr_layer = nil
    end
    if app.overlay == "maps" or app.overlay == "mapmaker" then
        app.overlay = nil
    end
    kit.reset_hover()
end

local function redraw(app)
    if app.overlay == "maps" then
        M.draw(app)
    end
end

-- The rooms a map can be set for: the adventure's, in map order.
local function rooms(app)
    local out = {}
    local st = app.campaign.adv
    for _, id in ipairs(adventure.data.order) do
        local r = adventure.data.rooms[id]
        if not r.virtual and not (st and st.skipped[id]) then
            table.insert(out, id)
        end
    end
    return out
end

local function where_used(app, ref)
    local st = app.campaign.adv
    local out = {}
    for _, id in ipairs(adventure.data.order) do
        if st and st.room_maps and st.room_maps[id] == ref then
            table.insert(out, util.lower_first(adventure.data.rooms[id].name))
        end
    end
    for _, sr in pairs((st and st.side_rooms) or {}) do
        if sr.ref == ref then
            table.insert(out, "a side room off " .. util.lower_first(adventure.data.rooms[sr.off].name))
        end
    end
    return out
end

-- The map, square by square: walls, doors, water, plants, pieces to hide behind; its places of
-- interest as numbered gold dots; where the heroes and the trouble start.
local function draw_preview(app, e, x, y)
    local pv = map_repo.preview(app.campaign, e.ref)
    if not pv then
        kit.text(x, y, "This map can't be shown.", "ui18", theme.faint)
        return
    end
    kit.box(x - 4, y - 4, pv.W * CELL + 8, pv.H * CELL + 8, kit.rgba("#000000", 0.3), { radius = 8 })
    for gy = 1, pv.H do
        for gx = 1, pv.W do
            local what = pv.cells[gx .. "," .. gy]
            local col = what and COLOURS[what] or kit.rgba("#2e2620")
            kit.box(x + (gx - 1) * CELL + 1, y + (gy - 1) * CELL + 1, CELL - 2, CELL - 2, col, { radius = 3 })
        end
    end
    local function start(at, label, col)
        if at then
            kit.dot(x + (at[1] - 0.5) * CELL, y + (at[2] - 0.5) * CELL, 18, col)
            kit.text(x + (at[1] - 0.5) * CELL, y + (at[2] - 0.5) * CELL - 9, label, "ui14", theme.ink, { pivot = gui.PIVOT_N })
        end
    end
    start(pv.party, "H", theme.teal)
    start(pv.foes, "!", theme.red)
    for i, pl in ipairs(e.places or {}) do
        if pl.x and pl.y then
            local cx, cy = x + (pl.x - 0.5) * CELL, y + (pl.y - 0.5) * CELL
            kit.dot(cx, cy, 22, theme.gold)
            kit.text(cx, cy - 9, util.int(i), "ui14", theme.ink, { pivot = gui.PIVOT_N })
        end
    end
end

local function list(app, entries, x, y, w, h)
    local group = app.mr_group or "adventure"
    -- The groups, as tabs across the top of the list.
    local present = {}
    for _, e in ipairs(entries) do
        present[e.group] = true
    end
    if not present[group] then
        for _, g in ipairs(map_repo.GROUPS) do
            if present[g] then
                group = g
                break
            end
        end
    end
    app.mr_group = group
    local ty = y
    local tx = x
    for _, g in ipairs(map_repo.GROUPS) do
        if present[g] or g == "mine" then
            local label = map_repo.GROUP_NAME[g]
            local tw = kit.width(label, "ui14") + 20
            if tx + tw > x + w then
                tx, ty = x, ty + 34
            end
            kit.button(tx, ty, tw, 28, label, function()
                app.mr_group = g
                app.mr_page = 1
                redraw(app)
            end, { font = "ui14", color = group == g and theme.go or theme.panel2, hover = theme.button_hover, key = "mr_group_" .. g })
            tx = tx + tw + 6
        end
    end
    local ly = ty + 42
    local shown = {}
    for _, e in ipairs(entries) do
        if e.group == group then
            table.insert(shown, e)
        end
    end
    local per = math.floor((y + h - ly - 40) / 56)
    local pages = math.max(1, math.ceil(#shown / per))
    local page = math.min(app.mr_page or 1, pages)
    if #shown == 0 then
        kit.text(x, ly, group == "mine" and "Nothing yet. \"New map\" starts one from scratch, or open any map and copy it."
            or "Nothing here yet.", "ui14", theme.faint, { w = w })
    end
    for i = (page - 1) * per + 1, math.min(#shown, page * per) do
        local e = shown[i]
        local on = app.mr_sel == e.ref
        kit.button(x, ly, w, 50, "", function()
            app.mr_sel = e.ref
            app.mr_pick = nil
            redraw(app)
        end, { color = on and theme.panel3 or theme.panel, hover = theme.button_hover, key = "mr_entry_" .. e.ref })
        kit.text(x + 12, ly + 6, e.title, "ui18b", on and theme.gold or theme.text, { w = w - 24, lines = 1 })
        local sub = e.about or (#(e.places or {}) > 0 and (util.int(#e.places) .. " places to go") or "")
        kit.text(x + 12, ly + 28, sub, "ui14", theme.dim, { w = w - 24, lines = 1 })
        ly = ly + 56
    end
    if pages > 1 then
        kit.button(x, y + h - 34, 90, 30, "<  Back", function()
            app.mr_page = math.max(1, page - 1)
            redraw(app)
        end, { font = "ui14", enabled = page > 1, key = "mr_prev" })
        kit.text(x + w / 2, y + h - 28, util.int(page) .. " of " .. util.int(pages), "ui14", theme.dim, { pivot = gui.PIVOT_N })
        kit.button(x + w - 90, y + h - 34, 90, 30, "More  >", function()
            app.mr_page = math.min(pages, page + 1)
            redraw(app)
        end, { font = "ui14", enabled = page < pages, key = "mr_next" })
    end
    return shown
end

-- Prep: set this map for a room, or open it as a side room off one. Game night: the next scene.
local function actions(app, e, x, y, w)
    local c = app.campaign
    local night = app.screen == "night"
    local by = y
    if night then
        local queued = app.night and app.night.map_next == e.ref
        kit.button(x, by, 260, 40, queued and "Next scene: here" or "Set the next scene here", function()
            if app.night then
                if app.night.map_next == e.ref then
                    app.night.map_next = nil
                else
                    app.night.map_next = e.ref
                end
            end
            redraw(app)
        end, { font = "ui18b", color = queued and theme.go or theme.button, hover = theme.go_hover, key = "mr_next_scene" })
        kit.text(x + 276, by + 10, queued and "The table sets it out when the next room starts. Click again to undo."
            or "Wherever the party goes next, it plays out on this map.", "ui14", theme.dim, { w = w - 280 })
        by = by + 52
    elseif c.module then
        kit.button(x, by, 220, 40, "Use for a room", function()
            app.mr_pick = (app.mr_pick ~= "room") and "room" or false
            redraw(app)
        end, { font = "ui18b", color = app.mr_pick == "room" and theme.go or theme.button, key = "mr_use_room" })
        kit.button(x + 232, by, 260, 40, "Open a side room off...", function()
            app.mr_pick = (app.mr_pick ~= "side") and "side" or false
            redraw(app)
        end, { font = "ui18b", color = app.mr_pick == "side" and theme.go or theme.button, key = "mr_side_room" })
        by = by + 50
        if app.mr_pick then
            kit.text(x, by, app.mr_pick == "room" and "Which room plays on this map? (Again to put its own board back.)"
                or "A side room off which room? The party can wander into it from there.", "ui14", theme.dim)
            by = by + 22
            local cx = x
            for _, id in ipairs(rooms(app)) do
                local r = adventure.data.rooms[id]
                local label = r.map or r.name
                local tw = kit.width(label, "ui14") + 20
                if cx + tw > x + w then
                    cx, by = x, by + 34
                end
                local on = app.mr_pick == "room" and map_repo.room_map(c, id) == e.ref
                kit.button(cx, by, tw, 28, label, function()
                    if app.mr_pick == "room" then
                        if on then
                            map_repo.set_room_map(c, id, nil)
                        else
                            map_repo.set_room_map(c, id, e.ref)
                        end
                    else
                        map_repo.add_side_room(c, e.ref, id)
                        app.mr_pick = nil
                    end
                    redraw(app)
                end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "mr_room_" .. id })
                cx = cx + tw + 6
            end
            by = by + 40
        end
    end
    -- Your maps open in the map maker; anything else as your own copy.
    kit.button(x, by, 220, 40, e.mine and "Open in the map maker" or "Copy and change it", function()
        local id = e.mine or map_repo.copy(c, e.ref)
        if id then
            app.mr_sel = "mine:" .. id
            app.mr_group = "mine"
            M.open_maker(app, id)
        end
    end, { font = "ui18b", key = "mr_edit" })
    if e.mine then
        kit.button(x + 232, by, 120, 40, "Delete", function()
            map_repo.delete(c, e.mine)
            app.mr_sel = nil
            redraw(app)
        end, { font = "ui18b", key = "mr_delete" })
    end
end

-- The map maker on one of your own maps (game/ui/map_view.lua, aimed at it).
function M.open_maker(app, id)
    app.map_target = { mine = id }
    app.overlay = "mapmaker"
    if app.mr_layer then
        kit.drop(app.mr_layer)
        app.mr_layer = nil
    end
    M.draw_maker(app)
end

function M.draw_maker(app)
    local map_view = require "game.ui.map_view"
    if app.mr_layer then
        kit.drop(app.mr_layer)
    end
    local l = kit.layer("maps", true)
    app.mr_layer = l
    local c = app.campaign
    local id = app.map_target and app.map_target.mine
    local m = id and (c.my_maps or {})[id]
    if m and not map_repo.pieces_of(c, id) then
        -- (Cleared in the map maker: start it again on open ground.)
        c.maps = c.maps or {}
        c.maps["mine:" .. id] = { v = 2, template = "blank", props = {}, removed = {}, traps = {}, week = c.week }
    end
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    kit.box(X, Y, W, H, theme.bg, { radius = 14 })
    kit.box(X, Y, W, 64, theme.panel, { radius = 14 })
    kit.text(X + 24, Y + 14, "MAP MAKER", "title30", theme.gold)
    kit.text(X + 24 + kit.width("MAP MAKER", "title30") + 30, Y + 22, m and m.name or "", "ui18", theme.dim)
    kit.button(X + W - 300, Y + 14, 150, 36, "<  All maps", function()
        app.map_target = nil
        M.open(app, id and ("mine:" .. id) or nil)
    end, { font = "ui18b", key = "mr_back" })
    kit.button(X + W - 140, Y + 14, 120, 36, "Done", function()
        app.map_target = nil
        M.close(app)
        if app.refresh then
            app.refresh()
        end
    end, { font = "ui18b", color = theme.go, hover = theme.go_hover, key = "mr_done" })
    if not m then
        kit.text(X + 24, Y + 90, "That map is gone.", "ui18", theme.faint)
        return
    end
    map_view.draw(app, X + 24, Y + 86, 760, H - 110, {}, nil)
    map_view.side(app, X + 816, Y + 86, W - 816 - 24, {}, nil)
end

function M.draw(app)
    if app.overlay == "mapmaker" then
        return M.draw_maker(app)
    end
    if app.mr_layer then
        kit.drop(app.mr_layer)
    end
    local l = kit.layer("maps", true)
    app.mr_layer = l
    local c = app.campaign
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    kit.box(X, Y, W, H, theme.bg, { radius = 14 })
    kit.box(X, Y, W, 64, theme.panel, { radius = 14 })
    kit.text(X + 24, Y + 14, "MAP REPOSITORY", "title30", theme.gold)
    kit.text(X + 24 + kit.width("MAP REPOSITORY", "title30") + 30, Y + 22,
        app.screen == "night" and "Every map you can put on the table. Pick where the next scene plays out."
            or "Every map you can put on the table: the adventure's, imported ones, and your own.", "ui18", theme.dim)
    kit.button(X + W - 330, Y + 14, 170, 36, "New map", function()
        local id = map_repo.new_map(c, app.mr_new_base or (c.module and "museum_hall") or "blank")
        app.mr_group = "mine"
        app.mr_sel = "mine:" .. id
        M.open_maker(app, id)
    end, { font = "ui18b", key = "mr_new" })
    kit.button(X + W - 140, Y + 14, 120, 36, "Done", function()
        M.close(app)
        if app.refresh then
            app.refresh()
        end
    end, { font = "ui18b", color = theme.go, hover = theme.go_hover, key = "mr_done" })
    local entries = map_repo.entries(c)
    local shown = list(app, entries, X + 24, Y + 86, 380, H - 110)
    local e = app.mr_sel and map_repo.find(c, app.mr_sel)
    if not e or e.group ~= app.mr_group then
        e = shown[1]
        app.mr_sel = e and e.ref or nil
    end
    if not e then
        return
    end
    local px, py = X + 430, Y + 86
    kit.text(px, py, e.title, "ui22b", theme.text)
    local used = where_used(app, e.ref)
    if #used > 0 then
        kit.text(px + kit.width(e.title, "ui22b") + 16, py + 6, "Set for " .. util.join_names(used) .. ".", "ui14", theme.gold)
    end
    draw_preview(app, e, px + 4, py + 40)
    -- Its places of interest, numbered as on the map.
    local lx = px + 20 * CELL + 30
    local ly = py + 36
    local lw = X + W - 24 - lx
    kit.text(lx, ly, "PLACES TO GO", "ui14", theme.dim)
    ly = ly + 22
    if #(e.places or {}) == 0 then
        kit.text(lx, ly, "No marked places: the table makes do with what's there.", "ui14", theme.faint, { w = lw })
    end
    for i, pl in ipairs(e.places or {}) do
        if ly > py + 40 + 13 * CELL - 30 then
            kit.text(lx, ly, "...and " .. util.int(#e.places - i + 1) .. " more", "ui14", theme.faint)
            break
        end
        local line = util.int(i) .. ".  " .. (pl.name or pl.id or "")
        kit.text(lx, ly, line, "ui14", theme.text, { w = lw, lines = 1 })
        ly = ly + 18
        if pl.line then
            local th = math.min(2 * kit.line_height("ui14"), kit.text_height(pl.line, "ui14", lw - 18))
            kit.text(lx + 18, ly, pl.line, "ui14", theme.dim, { w = lw - 18, lines = 2 })
            ly = ly + th + 4
        end
    end
    -- The key under the map.
    local ky = py + 40 + 13 * CELL + 12
    local kx = px
    for _, k in ipairs({ { "wall", "Walls" }, { "door", "Doors" }, { "cover", "Cover" }, { "water", "Water" },
                         { "plants", "Plants" }, { "rough", "Rough ground" } }) do
        kit.box(kx, ky + 2, 14, 14, COLOURS[k[1]], { radius = 3 })
        kit.text(kx + 20, ky, k[2], "ui14", theme.dim)
        kx = kx + 34 + kit.width(k[2], "ui14")
    end
    kit.text(kx + 10, ky, "H: heroes start.  !: trouble starts.  Gold: places to go.", "ui14", theme.dim)
    actions(app, e, px, ky + 32, W - (px - X) - 24)
end

return M
