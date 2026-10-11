-- Quick maps (M8, B9; the GDD's "Builders: Quick maps and encounters"). A map is drawn in prep
-- on the place's terrain template (one of the table's terrain sets, 20 x 13 squares): walls,
-- cover, rough ground and a trap on top of the set's own scenery, and where the party and the
-- monsters start. It's saved with the place, so going back there uses it, and it stands in for
-- the automatic staging. If the world changes the place, the map follows: a new state can bring
-- its own template (the pieces stay where they still fit). Pure Lua.

local content = require "game.model.content"
local util = require "game.model.util"

local M = {}

-- The pieces, in palette order. SRD 5.2.1: Half Cover is +2 to AC and Dexterity saves (Rules
-- Glossary, "Cover"); Difficult Terrain costs an extra foot per foot of movement (p. 15).
M.PIECES = {
    { id = "wall", name = "Wall", about = "Nobody moves through it." },
    { id = "cover", name = "Cover", about = "Half Cover from range: +2 AC." },
    { id = "rough", name = "Rough ground", about = "Difficult Terrain: double movement." },
    { id = "trap", name = "Trap", about = "Sprung by whoever steps on it." },
    { id = "party", name = "Party start", about = "Where the heroes come in." },
    { id = "foes", name = "Monster start", about = "Where the monsters wait." },
    { id = "erase", name = "Clear", about = "Take a piece off the map." },
}
M.BY_ID = {}
for _, p in ipairs(M.PIECES) do
    M.BY_ID[p.id] = p
end
M.MAX_PIECES = 40
M.TRAP = "hidden_pit"          -- the map's traps, until the DM picks another SRD trap
-- The general boards a map can be drawn on (a place with its own board offers that one first).
M.TEMPLATES = { "camp", "forest", "road", "ruins", "underground", "tavern", "town", "market_generic", "bridge", "dock", "blank" }

-- A place without a board of its own borrows one by what it is (A18's new places).
M.BY_SETTING = { { "ship", "dock" }, { "port", "dock" }, { "bridge", "bridge" }, { "tavern", "tavern" },
                 { "island", "dock" }, { "under", "underground" }, { "ruin", "ruins" }, { "vault", "underground" },
                 { "camp", "camp" }, { "water", "dock" }, { "crowd", "market_generic" }, { "town", "town" },
                 { "indoor", "tavern" }, { "road", "road" }, { "forest", "forest" }, { "wild", "forest" } }

local function key(x, y)
    return x .. "," .. y
end
M.key = key

local function split(k)
    local x, y = string.match(k, "^(%d+),(%d+)$")
    return tonumber(x), tonumber(y)
end
M.split = split

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

-- The saved map for a place, kept up to date with the world: a new state that brings its own
-- template swaps it, and pieces that land on the new set's scenery come off.
function M.get(campaign, lid)
    local m = lid and campaign.maps and campaign.maps[lid]
    if not m then
        return nil
    end
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

local function blocked_by_set(set_name)
    local layout = content.terrain_layout.sets[set_name] or content.terrain_layout.sets.blank
    local out = {}
    for _, sq in ipairs(layout.blocked) do
        out[key(sq[1], sq[2])] = true
    end
    return out, layout
end
M.blocked_by_set = blocked_by_set

-- Start a map for a place: its template, nothing drawn yet.
function M.new(campaign, lid, template)
    campaign.maps = campaign.maps or {}
    local _, state = place_state(campaign, lid)
    local m = { template = template, pieces = {}, week = campaign.week, state = state }
    campaign.maps[lid] = m
    return m
end

function M.remove(campaign, lid)
    if campaign.maps then
        campaign.maps[lid] = nil
    end
end

function M.count(m)
    local n = 0
    for _ in pairs(m.pieces) do
        n = n + 1
    end
    return n
end

-- Switch the template; pieces on the new set's scenery come off, starts move if they must.
function M.set_template(m, template)
    m.template = template
    local blocked = blocked_by_set(template)
    for k in pairs(m.pieces) do
        if blocked[k] then
            m.pieces[k] = nil
        end
    end
    for _, s in ipairs({ "party", "foes" }) do
        if m[s] and blocked[key(m[s][1], m[s][2])] then
            m[s] = nil
        end
    end
end

-- Put a piece on a square (or clear it). Returns true if the map changed.
function M.place(m, piece, x, y)
    local W, H = content.terrain_layout.W, content.terrain_layout.H
    if x < 1 or y < 1 or x > W or y > H then
        return false
    end
    local blocked = blocked_by_set(m.template)
    local k = key(x, y)
    if blocked[k] then
        return false                 -- the set's own scenery is already there
    end
    if piece == "erase" then
        local had = m.pieces[k] ~= nil
        m.pieces[k] = nil
        for _, s in ipairs({ "party", "foes" }) do
            if m[s] and m[s][1] == x and m[s][2] == y then
                m[s] = nil
                had = true
            end
        end
        return had
    elseif piece == "party" or piece == "foes" then
        if m.pieces[k] == "wall" then
            return false
        end
        m[piece] = { x, y }
        return true
    end
    if m.pieces[k] == piece then
        m.pieces[k] = nil            -- clicking a piece again takes it off
        return true
    end
    if not m.pieces[k] and M.count(m) >= M.MAX_PIECES then
        return false
    end
    if piece == "wall" then
        for _, s in ipairs({ "party", "foes" }) do
            if m[s] and m[s][1] == x and m[s][2] == y then
                return false
            end
        end
    end
    m.pieces[k] = piece
    return true
end

-- The layout a fight or a scene uses: the set's, with the map's walls, starts, cover, rough
-- ground and traps. Returns blocked (x * 1000 + y), layout, extras { cover, rough, traps }.
function M.layout(m)
    local base = content.terrain_layout.sets[m.template] or content.terrain_layout.sets.blank
    local blocked = {}
    for _, sq in ipairs(base.blocked) do
        blocked[sq[1] * 1000 + sq[2]] = true
    end
    local extras = { cover = {}, rough = {}, traps = {} }
    for k in pairs(base.cover or {}) do
        extras.cover[k] = true
    end
    for k in pairs(base.rough or {}) do
        extras.rough[k] = true
    end
    for k, kind in pairs(m.pieces) do
        local x, y = split(k)
        if kind == "wall" then
            blocked[x * 1000 + y] = true
        elseif kind == "cover" then
            extras.cover[k] = true
        elseif kind == "rough" then
            extras.rough[k] = true
        elseif kind == "trap" then
            extras.traps[k] = true
        end
    end
    local layout = { title = base.title, light = base.light, party = m.party or base.party, foes = m.foes or base.foes,
                     npc = base.npc, npc_at = base.npc_at, spots = base.spots, planks = base.planks, blocked = {} }
    for k in pairs(blocked) do
        table.insert(layout.blocked, { math.floor(k / 1000), k % 1000 })
    end
    return blocked, layout, extras
end

-- The pieces as square lists by kind, for the table to lay out.
function M.cells(m)
    local out = { wall = {}, cover = {}, rough = {}, trap = {} }
    local keys = {}
    for k in pairs(m.pieces) do
        table.insert(keys, k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local x, y = split(k)
        table.insert(out[m.pieces[k]], { x, y })
    end
    return out
end

-- How the map tilts the fight, for the difficulty meter: a share of the Moderate budget, and
-- the reasons. Cover by the monsters and traps make it harder; cover by the heroes and rough
-- ground in the monsters' way make it easier.
function M.tilt(m)
    if not m then
        return 0, {}
    end
    local _, layout = M.layout(m)
    local px, py = layout.party[1], layout.party[2]
    local fx, fy = layout.foes[1], layout.foes[2]
    local foe_cover, party_cover, foe_rough, party_rough, traps = 0, 0, 0, 0, 0
    for k, kind in pairs(m.pieces) do
        local x, y = split(k)
        local dp = math.max(math.abs(x - px), math.abs(y - py))
        local df = math.max(math.abs(x - fx), math.abs(y - fy))
        if kind == "cover" then
            if df < dp then foe_cover = foe_cover + 1 else party_cover = party_cover + 1 end
        elseif kind == "rough" then
            if df < dp then foe_rough = foe_rough + 1 else party_rough = party_rough + 1 end
        elseif kind == "trap" then
            traps = traps + 1
        end
    end
    local t = 0.04 * math.min(foe_cover, 4) - 0.03 * math.min(party_cover, 4) + 0.015 * math.min(foe_rough, 6)
        - 0.015 * math.min(party_rough, 6) + 0.05 * math.min(traps, 3)
    local why = {}
    if foe_cover > 0 then table.insert(why, util.int(foe_cover) .. " cover for the monsters") end
    if party_cover > 0 then table.insert(why, util.int(party_cover) .. " cover for the heroes") end
    if traps > 0 then table.insert(why, util.int(traps) .. (traps == 1 and " trap" or " traps")) end
    if foe_rough + party_rough > 0 then table.insert(why, util.int(foe_rough + party_rough) .. " rough ground") end
    return t, why
end

return M
