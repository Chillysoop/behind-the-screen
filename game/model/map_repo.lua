-- The map repository (v2, October 30): every map the DM can put on the table, in one place. The
-- adventure's own boards (built from its maps by tools/maps, game/data/map_library.lua), maps
-- imported from other books, the plain boards to start from, the other places the table already
-- has, and the DM's own maps, made from scratch or from a copy in the map maker. In prep the DM
-- sets a map for a room or opens a side room off one; on game night, the next scene's map. Pure Lua.
--
-- A map is named by a ref: "board:<board id>" for a built-in board, "mine:<id>" for one of the
-- DM's own: its name and places in campaign.my_maps[id], its pieces at campaign.maps["mine:<id>"]
-- (the same shape as a place's map in game/model/maps.lua, so the map maker edits it as it would
-- a place).

local util = require "game.model.util"
local boards = require "game.data.boards"
local board = require "game.model.board"
local maps = require "game.model.maps"
local adventure = require "game.model.adventure"

local M = {}

M.GROUPS = { "adventure", "mine", "imported", "basics", "places" }
M.GROUP_NAME = { adventure = "This adventure", mine = "Your maps", imported = "Imported", basics = "Start from",
                 places = "More places" }
M.BASIC_NAME = { camp = "Camp", forest = "Woods", road = "Road", ruins = "Ruins", underground = "Underground",
                 tavern = "Tavern", town = "Street", market_generic = "Market", bridge = "Bridge", dock = "Waterside",
                 blank = "Open ground", museum_hall = "Museum hall" }

local function mine(campaign)
    campaign.my_maps = campaign.my_maps or {}
    return campaign.my_maps
end

-- The pieces of one of the DM's own maps (nil if they cleared it).
local function pieces_of(campaign, id)
    local m = campaign.maps and campaign.maps["mine:" .. id]
    if m then
        maps.migrate(m)
    end
    return m
end
M.pieces_of = pieces_of

-- The library's own word for a board, and what it is.
local function board_title(id)
    local b = boards[id]
    return (b and b.title) or M.BASIC_NAME[id] or id
end

local function is_basic(id)
    return M.BASIC_NAME[id] ~= nil and (util.contains(maps.TEMPLATES, id) or id == "museum_hall")
end

-- Every entry, grouped and sorted: { ref, group, title, about, board, places, tags }.
function M.entries(campaign)
    local out = {}
    local module = campaign and campaign.module
    local ids = {}
    for id in pairs(boards) do
        if type(boards[id]) == "table" and boards[id].features then
            table.insert(ids, id)
        end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local b = boards[id]
        local group
        if b.adventure and b.adventure == module then
            group = "adventure"
        elseif b.adventure then
            group = nil                  -- another adventure's own rooms stay with it
        elseif b.source == "imported" then
            group = "imported"
        elseif is_basic(id) then
            group = "basics"
        elseif id ~= "vignette" then
            group = "places"
        end
        -- (While a module runs, nothing from the old valley shows: adventure.foreign.)
        if group and module and adventure.foreign(b.title or "") then
            group = nil
        end
        if group then
            table.insert(out, { ref = "board:" .. id, group = group, title = board_title(id), about = b.about,
                                board = id, places = b.places or {}, tags = b.tags or {}, room = b.room })
        end
    end
    local my = mine(campaign)
    local keys = {}
    for id in pairs(my) do
        table.insert(keys, id)
    end
    table.sort(keys)
    for _, id in ipairs(keys) do
        local m = my[id]
        table.insert(out, { ref = "mine:" .. id, group = "mine", title = m.name or "A map of my own",
                            about = "Made in the map maker" .. (m.week and (", session " .. util.int(m.week)) or "") .. ".",
                            mine = id, places = m.places or {}, tags = {} })
    end
    table.sort(out, function(a, b)
        local ga, gb = util.index_of(M.GROUPS, a.group), util.index_of(M.GROUPS, b.group)
        if ga ~= gb then
            return ga < gb
        end
        return a.title < b.title
    end)
    return out
end

function M.find(campaign, ref)
    for _, e in ipairs(M.entries(campaign)) do
        if e.ref == ref then
            return e
        end
    end
    return nil
end

-- The board id the table sets out for a ref, and the DM's map behind it (for the rules' layout).
function M.board_of(campaign, ref)
    if type(ref) ~= "string" then
        return nil
    end
    local kind, id = ref:match("^(%a+):(.+)$")
    if kind == "board" and boards[id] then
        return id, nil
    elseif kind == "mine" then
        local m = pieces_of(campaign, id)
        if m then
            return maps.board_id(m), m
        end
    end
    return nil
end

-- The template a ref stands on (what a scene's terrain is), and the DM's map if it's theirs.
function M.terrain_of(campaign, ref)
    local kind, id = (ref or ""):match("^(%a+):(.+)$")
    if kind == "board" and boards[id] then
        return id, nil
    elseif kind == "mine" then
        local m = pieces_of(campaign, id)
        if m then
            return m.template, m
        end
    end
    return nil
end

-- A new map of the DM's own, on a starting board ("blank" for open ground, any board id to draw on
-- top of it). Returns its id.
function M.new_map(campaign, template, name)
    local my = mine(campaign)
    campaign.my_map_n = (campaign.my_map_n or 0) + 1
    local id = "m" .. util.int(campaign.my_map_n)
    my[id] = { week = campaign.week, name = name or ("My map " .. util.int(campaign.my_map_n)) }
    campaign.maps = campaign.maps or {}
    campaign.maps["mine:" .. id] = { v = 2, template = boards[template] and template or "blank", props = {}, removed = {},
                                     traps = {}, week = campaign.week }
    return id
end

-- A copy of any map to change in the map maker (built-in boards stay as they are).
function M.copy(campaign, ref, name)
    local e = M.find(campaign, ref)
    if not e then
        return nil
    end
    if e.mine then
        local meta = mine(campaign)[e.mine]
        local src = pieces_of(campaign, e.mine) or { template = "blank" }
        local id = M.new_map(campaign, src.template, name or (meta.name .. " (copy)"))
        local m = pieces_of(campaign, id)
        m.props = util.copy(src.props or {})
        m.removed = util.copy(src.removed or {})
        m.traps = util.copy(src.traps or {})
        m.party, m.foes, m.light = src.party and util.copy(src.party), src.foes and util.copy(src.foes), src.light
        mine(campaign)[id].places = meta.places and util.copy(meta.places)
        return id
    end
    local id = M.new_map(campaign, e.board, name or (e.title .. ", my version"))
    mine(campaign)[id].places = util.copy(e.places or {})
    return id
end

function M.rename(campaign, id, name)
    local m = mine(campaign)[id]
    if m and name and name ~= "" then
        m.name = name
    end
end

function M.delete(campaign, id)
    mine(campaign)[id] = nil
    if campaign.maps then
        campaign.maps["mine:" .. id] = nil
    end
    -- Anything set to use it goes back to the room's own board.
    local st = campaign.adv
    for room, ref in pairs((st and st.room_maps) or {}) do
        if ref == "mine:" .. id then
            st.room_maps[room] = nil
        end
    end
    for sid, sr in pairs((st and st.side_rooms) or {}) do
        if sr.ref == "mine:" .. id then
            st.side_rooms[sid] = nil
        end
    end
end

-- Prep: this room plays on that map (nil puts the room's own board back).
function M.set_room_map(campaign, room, ref)
    local st = campaign.adv
    if not st then
        return
    end
    st.room_maps = st.room_maps or {}
    st.room_maps[room] = ref
end

function M.room_map(campaign, room)
    local st = campaign.adv
    return st and st.room_maps and st.room_maps[room] or nil
end

-- Prep: a side room off one of the adventure's rooms, on any map. The party can wander into it
-- from there (museum_night plays it: a look round its places of interest). Returns its id.
function M.add_side_room(campaign, ref, off, name)
    local st = campaign.adv
    if not (st and adventure.data.rooms[off]) then
        return nil
    end
    local e = M.find(campaign, ref)
    if not e then
        return nil
    end
    st.side_rooms = st.side_rooms or {}
    st.side_n = (st.side_n or 0) + 1
    local id = "side" .. util.int(st.side_n)
    st.side_rooms[id] = { ref = ref, off = off, name = name or e.title, places = util.copy(e.places or {}),
                          week = campaign.week }
    return id
end

function M.remove_side_room(campaign, id)
    local st = campaign.adv
    if st and st.side_rooms then
        st.side_rooms[id] = nil
    end
end

-- The side rooms off a room, in order.
function M.side_rooms_off(campaign, room)
    local st = campaign.adv
    local out = {}
    for id, sr in pairs((st and st.side_rooms) or {}) do
        if sr.off == room then
            table.insert(out, id)
        end
    end
    table.sort(out)
    return out
end

-- What a map's squares are, for the little preview: { [x..","..y] = "wall"|"cover"|"water"|"ground"|"plants"|"door" }.
local WATER = { pond = true, stream_ns = true, water_strip = true, puddle = true, ritual_basin = false }
local PLANTS = { hedge = true, topiary = true, oak = true, pine = true, bush = true, tall_grass = true, flowers = true,
                 dead_tree = true }
function M.preview(campaign, ref)
    local id = M.board_of(campaign, ref)
    if not id then
        return nil
    end
    local c = board.compile(id)
    local cells = {}
    for _, pc in ipairs(c.pieces) do
        local k = board.props[pc.kind]
        if k and not (k.flat and k.fw >= 20) then
            local what
            if k.door then
                what = "door"
            elseif WATER[pc.kind] then
                what = "water"
            elseif PLANTS[pc.kind] then
                what = "plants"
            elseif k.blocks and (k.deg == "total" or not k.cover) and (pc.kind:find("wall") or k.opaque) then
                what = "wall"
            elseif k.blocks then
                what = "cover"
            elseif k.flat then
                what = "ground"
            else
                what = "rough"
            end
            for _, sq in ipairs(board.squares(pc.kind, pc.x, pc.y, pc.r)) do
                local key = sq[1] .. "," .. sq[2]
                -- Walls and doors win a square over the floor under them.
                if not cells[key] or what == "wall" or what == "door" or cells[key] == "ground" then
                    cells[key] = what
                end
            end
        end
    end
    return { cells = cells, W = board.W, H = board.H, party = c.party, foes = c.foes, title = c.title }
end

return M
