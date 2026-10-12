-- Set the stage (the map builder, B9 rebuilt on the SRD): the DM dresses a place for a fight with
-- real set pieces from the table's prop kit (game/data/props.lua). A table is Half Cover, a pillar
-- Three-Quarters, a wall Total Cover; a door opens as someone walks through it, and a locked one
-- holds until it's picked or forced; ice is slippery; a torch lights the dark. The map is saved
-- with the place and is the place from then on: every scene there stands on it, and it's the board
-- the table sets out (game/model/board.lua registers it as a board of its own). Pure Lua.
--
-- campaign.maps[lid] = {
--   v = 2, template (the board it's drawn on), week, state (the world's state of the place),
--   props   = { { kind, x, y, r } }        the DM's pieces, in the order they went down
--   removed = { [feature id] = true }      the board's own scenery the DM took off
--   traps   = { ["x,y"] = true }, trap     hidden traps, and which SRD trap they are
--   party, foes = { x, y }                 where everyone starts
--   light   = nil | "bright" | "dim" | "dark"   nil: as the place is
-- }
-- Version 1 maps (painted squares: wall, cover, rough, trap) turn into pieces when loaded.

local content = require "game.model.content"
local util = require "game.model.util"
local board = require "game.model.board"
local props = require "game.data.props"

local M = {}

M.MAX_PIECES = 40
M.TRAP = "hidden_pit"          -- the map's traps, until the DM picks another SRD trap
-- The general boards a map can be drawn on (a place with its own board offers that one first).
M.TEMPLATES = { "camp", "forest", "road", "ruins", "underground", "tavern", "town", "market_generic", "bridge", "dock", "blank" }

-- A place without a board of its own borrows one by what it is (A18's new places).
M.BY_SETTING = { { "ship", "dock" }, { "port", "dock" }, { "bridge", "bridge" }, { "tavern", "tavern" },
                 { "island", "dock" }, { "under", "underground" }, { "ruin", "ruins" }, { "vault", "underground" },
                 { "camp", "camp" }, { "water", "dock" }, { "crowd", "market_generic" }, { "town", "town" },
                 { "indoor", "tavern" }, { "road", "road" }, { "forest", "forest" }, { "wild", "forest" } }

-- The palette, by what the pieces are for. kind: a prop kind; id: a tool that isn't a piece.
M.PALETTE = {
    { group = "Furniture", items = {
        { kind = "table_round", name = "Table" }, { kind = "table_long", name = "Long table" },
        { kind = "bench", name = "Bench" }, { kind = "bar", name = "Bar" }, { kind = "chest", name = "Chest" },
        { kind = "bookshelf", name = "Bookshelf" }, { kind = "bed", name = "Bed" }, { kind = "barrel", name = "Barrel" },
        { kind = "crate", name = "Crate" } } },
    { group = "Walls and doors", items = {
        { id = "wall", name = "Wall" }, { kind = "door", name = "Door" }, { kind = "wall_window", name = "Window" },
        { kind = "ruin_wall_low", name = "Low wall" }, { kind = "fence", name = "Fence" } } },
    { group = "Cover", items = {
        { kind = "pillar", name = "Pillar" }, { kind = "statue", name = "Statue" }, { kind = "oak", name = "Tree" },
        { kind = "boulder", name = "Boulder" }, { kind = "rock", name = "Rocks" }, { kind = "cart", name = "Cart" },
        { kind = "hay_bale", name = "Hay bale" } } },
    { group = "Ground", items = {
        { kind = "rubble", name = "Rubble" }, { kind = "bush", name = "Brush" }, { kind = "puddle", name = "Water" },
        { kind = "web", name = "Webs" }, { kind = "ice", name = "Ice" } } },
    { group = "Light", items = {
        { kind = "torch_post", name = "Torch" }, { kind = "brazier", name = "Brazier" }, { kind = "candelabra", name = "Candles" },
        { kind = "lamp_post", name = "Lamp post" }, { kind = "campfire", name = "Campfire" } } },
    { group = "Traps, starts", items = {
        { id = "trap", name = "Trap" }, { id = "party", name = "Heroes" }, { id = "foes", name = "Monsters" },
        { id = "erase", name = "Clear" } } },
}
M.ITEM = {}
for _, grp in ipairs(M.PALETTE) do
    for _, it in ipairs(grp.items) do
        M.ITEM[it.id or it.kind] = it
    end
end

-- The light over the whole map (SRD 5.2.1 "Light"): Bright Light; Dim Light is Lightly
-- Obscured; Darkness is Heavily Obscured, and a creature without Darkvision can't see into it.
M.LIGHTS = {
    { id = nil, name = "As the place is" },
    { id = "bright", name = "Bright", about = "Daylight, or a well-lit room. Everyone sees." },
    { id = "dim", name = "Dim", about = "Dusk, firelight, a gloomy hall: Lightly Obscured (Disadvantage on Perception by sight)." },
    { id = "dark", name = "Dark", about = "Night outside, an unlit cellar: Heavily Obscured. Only Darkvision, torches and fires see." },
}

local function key(x, y)
    return x .. "," .. y
end
M.key = key

local function split(k)
    local x, y = string.match(k, "^(%d+),(%d+)$")
    return tonumber(x), tonumber(y)
end
M.split = split

-- What a piece does, in a line of rules (SRD 5.2.1).
function M.rules_text(kind)
    local k = props[kind]
    if not k then
        return ""
    end
    local out = {}
    if k.door then
        table.insert(out, k.door == "open" and "An open door: walk through. Shut it again as you pass."
            or k.door == "locked" and "Locked: DC 15 to pick (Thieves' Tools) or DC 20 Strength to force. Wood, AC 15, 18 HP."
            or "Opens as someone walks through (a free interaction). Shut, it blocks sight. Wood, AC 15, 18 HP.")
    elseif k.opaque then
        table.insert(out, "Total Cover: blocks sight and movement.")
    elseif k.deg == "three_quarters" then
        table.insert(out, "Three-Quarters Cover: +5 AC and Dex saves behind it.")
    elseif k.deg == "half" then
        table.insert(out, "Half Cover: +2 AC and Dex saves behind it.")
    elseif k.blocks then
        table.insert(out, "Blocks movement.")
    end
    if k.slippery then
        table.insert(out, "Slippery: Difficult Terrain, and a DC 10 Dex save or Prone.")
    elseif k.rough then
        table.insert(out, "Difficult Terrain: every foot costs 2.")
    end
    if k.bright then
        table.insert(out, "Bright Light " .. util.int(k.bright) .. " ft, Dim " .. util.int(k.dim or 0) .. " ft more.")
    end
    return table.concat(out, " ")
end

-- The world's state of a place (S7), if it has one.
local function place_state(campaign, lid)
    local ledger = require "game.model.ledger"
    local nb = campaign.notebook
    if not nb then
        return nil, nil
    end
    local st = ledger.world_state(campaign).places[lid]
    return ledger.place_state(campaign, lid), st and st.state
end

-- The terrain set a place gets with no map: by the place, then by what it is, then by the scene.
function M.auto_template(campaign, loc, scene_type)
    local t = content.terrain
    if loc then
        local st = place_state(campaign, loc.id)
        if st and st.terrain then
            return st.terrain          -- the world changed the place (S7)
        end
        if t.by_location[loc.id] then
            return t.by_location[loc.id]
        end
        for _, pair in ipairs(M.BY_SETTING) do
            if util.contains(loc.setting or {}, pair[1]) then
                return pair[2]
            end
        end
    end
    return t.by_scene[scene_type or "combat"] or "blank"
end

-- The wall that suits the board: plaster indoors on floorboards, stone everywhere else.
function M.wall_kind(template)
    local c = board.compile(template)
    for _, pc in ipairs(c.pieces) do
        if pc.kind == "floor_boards" then
            return "wall_room"
        end
    end
    return "stone_wall"
end

-- Version 1 maps painted squares; each becomes a piece that does the same thing.
function M.migrate(m)
    if m.v == 2 then
        return m
    end
    m.v = 2
    m.props = m.props or {}
    m.removed = m.removed or {}
    m.traps = m.traps or {}
    local wall = M.wall_kind(m.template)
    local keys = {}
    for k in pairs(m.pieces or {}) do
        table.insert(keys, k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local what = m.pieces[k]
        local x, y = split(k)
        if what == "trap" then
            m.traps[k] = true
        else
            local kind = (what == "wall" and wall) or (what == "cover" and "crate") or (what == "rough" and "rubble")
            if kind then
                table.insert(m.props, { kind = kind, x = x, y = y, r = 0 })
            end
        end
    end
    m.pieces = nil
    return m
end

-- The saved map for a place, kept up to date with the world: a new state that brings its own
-- template swaps it, and pieces that land on the new set's scenery come off.
function M.get(campaign, lid)
    local m = lid and campaign.maps and campaign.maps[lid]
    if not m then
        return nil
    end
    M.migrate(m)
    local st, state = place_state(campaign, lid)
    if state ~= m.state then
        m.changed = state            -- the builder says so
        m.state = state
        if st and st.terrain and st.terrain ~= m.template then
            M.set_template(m, st.terrain)
        end
    end
    return m
end

-- The template a scene at this place is staged on.
function M.template(campaign, loc, scene_type)
    local m = loc and M.get(campaign, loc.id)
    if m then
        return m.template
    end
    return M.auto_template(campaign, loc, scene_type)
end

-- Start a map for a place: its template, nothing drawn yet.
function M.new(campaign, lid, template)
    campaign.maps = campaign.maps or {}
    local _, state = place_state(campaign, lid)
    local m = { v = 2, template = template, props = {}, removed = {}, traps = {}, week = campaign.week, state = state }
    campaign.maps[lid] = m
    return m
end

function M.remove(campaign, lid)
    if campaign.maps then
        campaign.maps[lid] = nil
    end
end

function M.count(m)
    local n = #(m.props or {})
    for _ in pairs(m.traps or {}) do
        n = n + 1
    end
    return n
end

-- The board's own scenery: blocked squares, and which feature each square belongs to.
local function base_squares(template)
    local c = board.compile(template)
    local blocked, owner = {}, {}
    for _, sq in ipairs(c.blocked) do
        blocked[key(sq[1], sq[2])] = true
    end
    for _, feat in ipairs(c.features) do
        if not feat.base then
            for _, idx in ipairs(feat.pieces) do
                local pc = c.pieces[idx]
                for _, sq in ipairs(board.squares(pc.kind, pc.x, pc.y, pc.r)) do
                    owner[key(sq[1], sq[2])] = feat.id
                end
            end
        end
    end
    return blocked, owner, c
end

-- The squares a piece covers (all of them, or nil if it hangs off the mat).
local function footprint(kind, x, y, r)
    local k = props[kind]
    local sqs = board.squares(kind, x, y, r)
    if not k or #sqs ~= k.fw * k.fh then
        return nil
    end
    return sqs
end
M.footprint = footprint

-- Which of the DM's pieces covers a square: index, piece.
function M.piece_at(m, x, y)
    for i = #m.props, 1, -1 do
        local p = m.props[i]
        for _, sq in ipairs(board.squares(p.kind, p.x, p.y, p.r)) do
            if sq[1] == x and sq[2] == y then
                return i, p
            end
        end
    end
    return nil
end

-- Squares the map's own pieces block (with the board's scenery the DM left).
local function blocked_now(m)
    local base, owner = base_squares(m.template)
    local out = {}
    for k in pairs(base) do
        if not (owner[k] and m.removed[owner[k]]) then
            out[k] = true
        end
    end
    for _, p in ipairs(m.props) do
        for _, sq in ipairs(board.squares(p.kind, p.x, p.y, p.r)) do
            if sq[3] then
                out[key(sq[1], sq[2])] = true
            end
        end
    end
    return out
end
M.blocked_now = blocked_now

-- Switch the template; pieces that land on the new set's scenery come off, starts move if they must.
function M.set_template(m, template)
    M.migrate(m)
    m.template = template
    m.removed = {}
    local base = base_squares(template)
    for i = #m.props, 1, -1 do
        local p = m.props[i]
        for _, sq in ipairs(board.squares(p.kind, p.x, p.y, p.r)) do
            if base[key(sq[1], sq[2])] then
                table.remove(m.props, i)
                break
            end
        end
    end
    for k in pairs(m.traps) do
        if base[k] then
            m.traps[k] = nil
        end
    end
    local blocked = blocked_now(m)
    for _, s in ipairs({ "party", "foes" }) do
        if m[s] and blocked[key(m[s][1], m[s][2])] then
            m[s] = nil
        end
    end
end

local DOOR_NEXT = { door = "door_open", door_open = "door_locked", door_locked = "door" }

-- Put a piece (or a trap, a start) on a square, turned r quarters, or clear what's there.
-- Clicking one of the DM's own pieces with the same tool turns it (a door cycles shut, open,
-- locked). Returns true if the map changed, or false and why not.
function M.place(m, tool, x, y, r)
    M.migrate(m)
    local W, H = content.terrain_layout.W, content.terrain_layout.H
    if x < 1 or y < 1 or x > W or y > H then
        return false
    end
    r = (r or 0) % 4
    local k = key(x, y)
    local base, owner = base_squares(m.template)
    local at, piece = M.piece_at(m, x, y)
    if tool == "erase" then
        if at then
            table.remove(m.props, at)
            return true
        elseif m.traps[k] then
            m.traps[k] = nil
            return true
        end
        for _, s in ipairs({ "party", "foes" }) do
            if m[s] and m[s][1] == x and m[s][2] == y then
                m[s] = nil
                return true
            end
        end
        if owner[k] and not m.removed[owner[k]] then
            m.removed[owner[k]] = true        -- the board's own table, crates or tree come off
            return true
        end
        return false
    end
    local blocked = blocked_now(m)
    if tool == "party" or tool == "foes" then
        if blocked[k] then
            return false, "Something's standing there."
        end
        m[tool] = { x, y }
        return true
    end
    if tool == "trap" then
        if blocked[k] then
            return false, "A trap goes on open ground."
        end
        m.traps[k] = not m.traps[k] or nil
        return true
    end
    -- (Version 1's painted squares, by their old names.)
    tool = ({ cover = "crate", rough = "rubble" })[tool] or tool
    local kind = tool == "wall" and M.wall_kind(m.template) or tool
    if not props[kind] then
        return false
    end
    -- The same piece again: turn it, or work the door.
    if piece and (piece.kind == kind or (DOOR_NEXT[piece.kind] and DOOR_NEXT[kind])) then
        if DOOR_NEXT[piece.kind] then
            piece.kind = DOOR_NEXT[piece.kind]
            return true
        end
        local nr = (piece.r + 1) % 4
        local fp = footprint(piece.kind, piece.x, piece.y, nr)
        if not fp then
            return false, "It doesn't fit turned that way."
        end
        for _, sq in ipairs(fp) do
            local kk = key(sq[1], sq[2])
            local j = M.piece_at(m, sq[1], sq[2])
            if (base[kk] and not (owner[kk] and m.removed[owner[kk]])) or (j and j ~= at) then
                return false, "It doesn't fit turned that way."
            end
        end
        piece.r = nr
        return true
    end
    if piece then
        table.remove(m.props, at)       -- another piece goes down in its place
    end
    if #m.props >= M.MAX_PIECES then
        return false, "That's plenty of pieces for one map."
    end
    local fp = footprint(kind, x, y, r)
    if not fp then
        return false, "It doesn't fit there."
    end
    for _, sq in ipairs(fp) do
        local kk = key(sq[1], sq[2])
        if base[kk] and not (owner[kk] and m.removed[owner[kk]]) then
            return false, "The place's own scenery is there. Clear it first."
        end
        if M.piece_at(m, sq[1], sq[2]) then
            return false, "Another piece is in the way."
        end
        if sq[3] then
            for _, s in ipairs({ "party", "foes" }) do
                if m[s] and m[s][1] == sq[1] and m[s][2] == sq[2] then
                    return false, "That's where someone starts."
                end
            end
            m.traps[kk] = nil
        end
    end
    table.insert(m.props, { kind = kind, x = x, y = y, r = r })
    M.align_walls(m, x, y)
    return true
end

-- Walls, doors, windows and fences line up with their neighbours, so a line drawn down the mat
-- runs north-south without turning each piece by hand.
local WALLISH = { stone_wall = true, wall_room = true, wall_window = true, door = true, door_open = true,
                  door_locked = true, ruin_wall_low = true, fence = true }
function M.align_walls(m, x, y)
    local at = {}
    for _, p in ipairs(m.props) do
        if WALLISH[p.kind] then
            at[key(p.x, p.y)] = p
        end
    end
    local function align(p)
        local ns = at[key(p.x, p.y - 1)] or at[key(p.x, p.y + 1)]
        local ew = at[key(p.x - 1, p.y)] or at[key(p.x + 1, p.y)]
        if ns and not ew then
            p.r = 1
        elseif ew and not ns then
            p.r = 0
        end
    end
    local here = at[key(x, y)]
    if not here then
        return
    end
    align(here)
    for _, d in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
        local p = at[key(x + d[1], y + d[2])]
        if p then
            align(p)
        end
    end
end

-- The map as a board of its own: its id (registered with board.lua), and the def behind it.
local function fingerprint(m)
    local parts = { m.template }
    for _, p in ipairs(m.props) do
        table.insert(parts, p.kind .. "@" .. p.x .. "," .. p.y .. "," .. p.r)
    end
    local rem = {}
    for fid in pairs(m.removed) do
        table.insert(rem, fid)
    end
    table.sort(rem)
    table.insert(parts, "-" .. table.concat(rem, "-"))
    if m.party then
        table.insert(parts, "P" .. m.party[1] .. "," .. m.party[2])
    end
    if m.foes then
        table.insert(parts, "F" .. m.foes[1] .. "," .. m.foes[2])
    end
    local s = table.concat(parts, ";")
    local h1, h2 = 5381, 52711
    for i = 1, #s do
        local b = string.byte(s, i)
        h1 = (h1 * 33 + b) % 4294967296
        h2 = (h2 * 31 + b) % 4294967296
    end
    return string.format("%08x%08x", h1, h2)
end

function M.board_id(m)
    M.migrate(m)
    if #m.props == 0 and next(m.removed) == nil and not m.party and not m.foes then
        return m.template
    end
    local id = "map:" .. m.template .. ":" .. fingerprint(m)
    if not board.registered(id) then
        local add = {}
        for _, p in ipairs(m.props) do
            table.insert(add, { kind = p.kind, x = p.x, y = p.y, r = p.r })
        end
        local removed = {}
        for fid in pairs(m.removed) do
            removed[fid] = true
        end
        board.register(id, { base = m.template, add = add, removed = removed, party = m.party, foes = m.foes })
    end
    return id
end

-- The layout a fight or a scene uses: the map's board, its starts, traps, light and doors.
-- Returns blocked (x * 1000 + y), layout, extras.
function M.layout(m)
    local id = M.board_id(m)
    local c = board.compile(id)
    local blocked = {}
    for _, sq in ipairs(c.blocked) do
        blocked[sq[1] * 1000 + sq[2]] = true
    end
    local extras = { cover = {}, deg = {}, rough = {}, traps = {}, planks = c.planks, sources = c.sources, opaque = {},
                     doors = {}, slippery = {}, lights = c.lights, light = m.light, board = id }
    for k, what in pairs(c.cover) do
        extras.cover[k] = what
        extras.deg[k] = c.deg[k]
    end
    for k in pairs(c.rough) do
        extras.rough[k] = true
    end
    for k in pairs(c.opaque) do
        extras.opaque[k] = true
    end
    for k in pairs(c.slippery) do
        extras.slippery[k] = true
    end
    for _, d in ipairs(c.doors) do
        table.insert(extras.doors, d)
    end
    for k in pairs(m.traps) do
        extras.traps[k] = true
    end
    local layout = { title = c.title, light = c.light, party = m.party or c.party, foes = m.foes or c.foes,
                     npc = c.npc, npc_at = c.npc_at, spots = c.spots, planks = c.planks, sources = c.sources, blocked = c.blocked }
    return blocked, layout, extras
end

-- What the table lays as paper on the mat: only the hidden traps (the rest are real pieces now).
function M.cells(m)
    local out = { trap = {} }
    local keys = {}
    for k in pairs(m.traps or {}) do
        table.insert(keys, k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local x, y = split(k)
        table.insert(out.trap, { x, y })
    end
    return out
end

-- How the map tilts the fight, for the difficulty meter: a share of the Moderate budget, and
-- the reasons. Cover by the monsters, traps and the dark make it harder; cover by the heroes,
-- light and rough ground in the monsters' way make it easier.
function M.tilt(m)
    if not m then
        return 0, {}
    end
    M.migrate(m)
    local _, layout = M.layout(m)
    local px, py = layout.party[1], layout.party[2]
    local fx, fy = layout.foes[1], layout.foes[2]
    local foe_cover, party_cover, foe_rough, party_rough, traps, lights_foe = 0, 0, 0, 0, 0, 0
    for _, p in ipairs(m.props) do
        local k = props[p.kind] or {}
        local dp = math.max(math.abs(p.x - px), math.abs(p.y - py))
        local df = math.max(math.abs(p.x - fx), math.abs(p.y - fy))
        local w = k.deg == "three_quarters" and 1.5 or 1
        if k.deg then
            if df < dp then foe_cover = foe_cover + w else party_cover = party_cover + w end
        elseif k.rough then
            if df < dp then foe_rough = foe_rough + 1 else party_rough = party_rough + 1 end
        end
        if k.bright and df < dp then
            lights_foe = lights_foe + 1
        end
    end
    for _ in pairs(m.traps) do
        traps = traps + 1
    end
    local t = 0.04 * math.min(foe_cover, 4) - 0.03 * math.min(party_cover, 4) + 0.015 * math.min(foe_rough, 6)
        - 0.015 * math.min(party_rough, 6) + 0.05 * math.min(traps, 3)
    local why = {}
    if m.light == "dark" then
        t = t + 0.08 - 0.03 * math.min(lights_foe, 2)
        table.insert(why, lights_foe > 0 and "the dark (with light by the monsters)" or "the dark")
    end
    if foe_cover > 0 then table.insert(why, util.int(math.floor(foe_cover + 0.5)) .. " cover for the monsters") end
    if party_cover > 0 then table.insert(why, util.int(math.floor(party_cover + 0.5)) .. " cover for the heroes") end
    if traps > 0 then table.insert(why, util.int(traps) .. (traps == 1 and " trap" or " traps")) end
    if foe_rough + party_rough > 0 then table.insert(why, util.int(foe_rough + party_rough) .. " rough ground") end
    return t, why
end

return M
